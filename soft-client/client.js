const msgbus = require("./msgbus");

const mb = msgbus.connect()
mb.prepare("wallet.stellar.balance.tft", [4], 0, 2)
mb.send("GA7OPN4A3JNHLPHPEWM4PJDOYYDYNZOM7ES6YL3O7NC3PRY3V3UX6ANM")
mb.read(function (result) {
    console.log("result received");
    console.log(result);

    console.log("closing");
    process.exit(0);
})


/*
mb.prepare("griddb.twins.create", [1002], 0)
mb.send("some_peer_id")
values = mb.read()

console.log(values)

mb.prepare("griddb.twins.get", [1002], 0)
mb.send(1)
values = mb.read()

console.log(values)
*/
