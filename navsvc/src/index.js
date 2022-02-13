const express = require('express')
const fetch = require('node-fetch');
const app = express()
const port = 80

app.get('/:lat1/:lon1/:lat2/:lon2', async (req, res) => {
    const { lat1, lon1, lat2, lon2 } = req.params;
    const response = await fetch(`http://ors-service/ors/v2/directions/driving-car?start=${lat1},${lon1}&end=${lat2},${lon2}`)
    res.send(await response.json())
})

app.listen(port, () => {
  console.log(`Example app listening on port ${port}`)
})

process.on('SIGINT', function() {
    console.log("Caught interrupt signal");
    process.exit();
});