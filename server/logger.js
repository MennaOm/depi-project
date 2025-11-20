const winston = require("winston");

// Create logger
const logger = winston.createLogger({
  level: "info",
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: "hotel-booking-backend" },
  transports: [
    // Write all logs to console
    new winston.transports.Console({
      format: winston.format.simple(),
    }),
    // Write all errors to error.log
    new winston.transports.File({
      filename: "logs/error.log",
      level: "error",
    }),
    // Write all logs to combined.log
    new winston.transports.File({
      filename: "logs/combined.log",
    }),
  ],
});

// Logging middleware
const loggingMiddleware = (req, res, next) => {
  const start = Date.now();

  res.on("finish", () => {
    const duration = Date.now() - start;
    logger.info("HTTP request", {
      method: req.method,
      url: req.url,
      status: res.statusCode,
      duration: `${duration}ms`,
      userAgent: req.get("User-Agent"),
    });
  });

  next();
};

module.exports = {
  logger,
  loggingMiddleware,
};
