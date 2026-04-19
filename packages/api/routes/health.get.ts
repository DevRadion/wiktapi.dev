import { defineHandler, createError } from "nitro/h3";
import { db } from "../utils/db.ts";

export default defineHandler((_event) => {
  try {
    db.prepare("SELECT 1").get();
    return { status: "ok", db: true };
  } catch {
    throw createError({ statusCode: 503, message: "Database unavailable" });
  }
});
