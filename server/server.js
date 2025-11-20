import express from "express";
import "dotenv/config";
import cors from "cors";
import connectDB from "./configs/db.js";
import { clerkMiddleware } from "@clerk/express";
import userRouter from "./routes/userRoutes.js";
import hotelRouter from "./routes/hotelRoutes.js";
import roomRouter from "./routes/roomRoutes.js";
import bookingRouter from "./routes/bookingRoutes.js";
import clerkWebhooks from "./controllers/clerkWebhooks.js";
import connectCloudinary from "./configs/cloudinary.js";
import { stripeWebhooks } from "./controllers/stripeWebhooks.js";
import eventRouter from "./routes/eventRoutes.js";
import chatRouter from "./routes/chatRoutes.js";

// IMPORTS
import client from "prom-client";
import winston from "winston";

// METRICS SETUP
const register = new client.Registry();
client.collectDefaultMetrics({ register });

// Custom application metrics
const httpRequestCounter = new client.Counter({
  name: "http_requests_total",
  help: "Total HTTP requests",
  labelNames: ["method", "route", "status_code"],
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

// LOGGER SETUP
const logger = winston.createLogger({
  level: "info",
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.errors({ stack: true }),
    winston.format.json()
  ),
  defaultMeta: { service: "hotel-booking-backend" },
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        winston.format.simple()
      ),
    }),
  ],
});

connectDB();
connectCloudinary();

const app = express();

// METRICS MIDDLEWARE (BEFORE OTHER MIDDLEWARE)
app.use((req, res, next) => {
  if (req.path === "/metrics") {
    res.set("Content-Type", register.contentType);
    res.end(register.metrics());
  } else {
    next();
  }
});

app.use(
  cors({
    origin: "*",
    methods: "*",
    allowedHeaders: "*",
  })
);

// LOGGING MIDDLEWARE
app.use((req, res, next) => {
  const start = Date.now();

  res.on("finish", () => {
    const duration = Date.now() - start;

    // Log the request
    logger.info("HTTP request", {
      method: req.method,
      url: req.url,
      statusCode: res.statusCode,
      duration: `${duration}ms`,
      userAgent: req.get("User-Agent"),
    });

    // Count requests for metrics
    httpRequestCounter
      .labels(req.method, req.route?.path || req.path, res.statusCode)
      .inc();
    httpRequestDuration
      .labels(req.method, req.route?.path || req.path)
      .observe(duration / 1000);
  });

  next();
});

// API to listen to Stripe Webhooks
app.post(
  "/api/stripe",
  express.raw({ type: "application/json" }),
  stripeWebhooks
);

// Middleware to parse JSON
app.use(express.json());
app.use(clerkMiddleware());

// API to listen to Clerk Webhooks
app.use("/api/clerk", clerkWebhooks);

// HEALTH ENDPOINT (NO AUTH REQUIRED)
app.get("/health", (req, res) => {
  res.json({
    status: "healthy",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
    environment: process.env.NODE_ENV || "development",
  });
});

//app.get("/", (req, res) => res.send("API is working"));
//app.use("/api/user", userRouter);
//app.use("/api/hotels", hotelRouter);
//app.use("/api/rooms", roomRouter);
//app.use("/api/bookings", bookingRouter);
app.use("/api/event", eventRouter);
//app.use("/api/chat", chatRouter);

// ERROR HANDLING MIDDLEWARE (AT THE END)
app.use((error, req, res, next) => {
  errorCounter.labels("unhandled_error").inc();

  logger.error("Unhandled error", {
    error: error.message,
    stack: error.stack,
    url: req.url,
    method: req.method,
    userId: req.auth?.userId, // Clerk user ID if available
  });

  res.status(500).json({
    error: "Internal server error",
    message:
      process.env.NODE_ENV === "production"
        ? "Something went wrong"
        : error.message,
  });
});

// 404 HANDLER
app.use("*", (req, res) => {
  logger.warn("404 Not Found", {
    url: req.originalUrl,
    method: req.method,
    ip: req.ip,
  });

  res.status(404).json({ error: "Route not found" });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  logger.info(`Server running on port ${PORT}`, {
    port: PORT,
    environment: process.env.NODE_ENV || "development",
    nodeVersion: process.version,
  });
});
