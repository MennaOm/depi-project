const client = require("prom-client");

// Create metrics registry
const register = new client.Registry();
client.collectDefaultMetrics({ register });

// Custom application metrics
const httpRequestCounter = new client.Counter({
  name: "http_requests_total",
  help: "Total HTTP requests",
  labelNames: ["method", "route", "status"],
});

const httpRequestDuration = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "HTTP request duration in seconds",
  labelNames: ["method", "route"],
  buckets: [0.1, 0.5, 1, 2, 5],
});

const bookingCounter = new client.Counter({
  name: "bookings_total",
  help: "Total bookings created",
  labelNames: ["status"],
});

const errorCounter = new client.Counter({
  name: "errors_total",
  help: "Total application errors",
  labelNames: ["type"],
});

// Register metrics
register.registerMetric(httpRequestCounter);
register.registerMetric(httpRequestDuration);
register.registerMetric(bookingCounter);
register.registerMetric(errorCounter);

// Metrics endpoint
const metricsMiddleware = (req, res, next) => {
  if (req.path === "/metrics") {
    res.set("Content-Type", register.contentType);
    res.end(register.metrics());
  } else {
    next();
  }
};

module.exports = {
  metricsMiddleware,
  httpRequestCounter,
  httpRequestDuration,
  bookingCounter,
  errorCounter,
};
