const express = require('express');
const app = express();
const port = process.env.PORT || 3000;
const os = require('os');

app.get('/', (req, res) => {
  res.send(`Dockerized single endpoint server — served by ${os.hostname()}`);
});

app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

app.listen(port, () => {
  console.log(`App listening on port ${port}`);
});