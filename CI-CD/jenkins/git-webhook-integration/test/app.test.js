import assert from "node:assert/strict";
import http from "node:http";
import { test } from "node:test";

import { startServer } from "../app.js";

function getJson(port, path) {
  return new Promise((resolve, reject) => {
    const req = http.get({ hostname: "127.0.0.1", port, path }, (res) => {
      let body = "";

      res.setEncoding("utf8");
      res.on("data", (chunk) => {
        body += chunk;
      });
      res.on("end", () => {
        resolve({
          statusCode: res.statusCode,
          body: JSON.parse(body),
        });
      });
    });

    req.on("error", reject);
  });
}

test("GET /health returns ok", async () => {
  const server = startServer(0);
  const port = server.address().port;

  try {
    const response = await getJson(port, "/health");

    assert.equal(response.statusCode, 200);
    assert.equal(response.body.status, "ok");
  } finally {
    server.close();
  }
});

test("GET / returns deployment message", async () => {
  const server = startServer(0);
  const port = server.address().port;

  try {
    const response = await getJson(port, "/");

    assert.equal(response.statusCode, 200);
    assert.match(response.body.message, /Jenkins webhook/);
  } finally {
    server.close();
  }
});
