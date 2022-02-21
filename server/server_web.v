module server

import json
import vweb
import rand
import despiegk.crystallib.resp2
import encoding.base64

struct App {
	vweb.Context
mut:
	config MBusSrv [vweb_global]
}

fn (mut srv MBusSrv) run_web() ? {
	app := App{
		config: srv
	}
	vweb.run(app, 8051)
}

/*
* Handle Request from zbus-remote endpoint
* Decode and validate msg, push it in msgbus.system.remote queue
*/
['/zbus-remote'; post]
pub fn (mut app App) zbus_web_remote() vweb.Result {
	mut redis := app.config.redis

	if app.config.debugval > 0 {
		println('[+] request from external agent')
		println(app.req.data)
	}

	_ := json.decode(Message, app.req.data) or {
		return app.json('{"status": "error", "message": "could not parse message request"}')
	}

	// forward request to local redis
	redis.lpush('msgbus.system.remote', app.req.data) or {
		return app.json('{"status": "error", "message": "could not send message to remote"}')
	}

	return app.json('{"status": "accepted"}')
}

/*
* Handle Request from zbus-reply endpoint
* Decode and validate msg, push it in msgbus.system.reply queue
*/
['/zbus-reply'; post]
pub fn (mut app App) zbus_web_reply() vweb.Result {
	mut redis := app.config.redis

	if app.config.debugval > 0 {
		println('[+] reply from external agent')
		println(app.req.data)
	}

	_ := json.decode(Message, app.req.data) or {
		return app.json('{"status": "error", "message": "could not parse message request"}')
	}

	// forward request to local redis
	redis.lpush('msgbus.system.reply', app.req.data) or {
		return app.json('{"status": "error", "message": "could not send message to reply"}')
	}

	return app.json('{"status": "accepted"}')
}

/*
* Handle Request from zbus-cmd endpoint
* This endpoint related to requests came from gridproxy to run a command
* Decode, validate and add retqueue to the msg, push it in msgbus.system.remote queue
*/
['/zbus-cmd'; post]
pub fn (mut app App) zbus_http_cmd() vweb.Result {
	if app.config.debugval > 0 {
		println('[+] request from external agent through zbus-cmd endpoint')
		println(app.req.data)
	}

	mut msg := json.decode(Message, app.req.data) or {
		return app.json('{"status": "error", "message": "could not parse message request"}')
	}
	msg.proxy = true
	msg.retqueue = rand.uuid_v4()
	encoded_msg := json.encode_pretty(msg)
	mut redis := app.config.redis

	// forward request to local redis
	redis.lpush('msgbus.system.remote', encoded_msg) or { panic(err) }

	return app.json('{"retqueue": "$msg.retqueue"}')
}

/*
* Handle Request from zbus-result endpoint
* This endpoint related to requests came from gridproxy to get result
* Get result using retqueue
*/
['/zbus-result'; post]
pub fn (mut app App) zbus_http_result() vweb.Result {
	if app.config.debugval > 0 {
		println('[+] request from external agent through zbus-result endpoint')
		println(app.req.data)
	}
	mid := json.decode(MessageIdentifier, app.req.data) or {
		panic('Failed to parse json with error: $err')
	}
	is_valid_retqueue := is_valid_uuid(mid.retqueue) or {
		panic('Failed to check valid uuid with error: $err')
	}
	if !is_valid_retqueue {
		return app.json('{"status": "error", "message": "Invalid Retqueue, it should be a valid UUID"}')
	}
	mut redis := app.config.redis
	lr := redis.lrange(mid.retqueue, 0, -1) or {
		return app.json('{"status": "error", "message": "Error fetching from redis $err"}')
	}
	mut responses := []Message{}
	for v in lr {
		rv := resp2.get_redis_value(v)
		mut m := json.decode(Message, rv) or {
			eprintln(err)
			Message{}
		}
		m.data = base64.decode_str(m.data)
		responses << m
	}
	return app.json(json.encode(responses))
}
