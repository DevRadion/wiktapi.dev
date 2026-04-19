import Database from "better-sqlite3";
import { existsSync } from "node:fs";
import { resolve, dirname } from "node:path";

const dbPath = process.env.DATA_PATH ?? resolve("./data/wiktionary.db");

console.log("Opening database at", dbPath);

if (!existsSync(dirname(dbPath))) {
  console.error("Error: Directory", dirname(dbPath), "does not exist.");
  console.error("Make sure your volume is mounted at the correct path.");
  process.exit(1);
}

if (!existsSync(dbPath)) {
  console.error("Error: Database file", dbPath, "not found.");
  console.error("Run the import worker first: docker compose run worker import");
  process.exit(1);
}

export const db = new Database(dbPath, { readonly: true });

// Necessary pragma settings for performance; these are safe for read-only access on a server with at least 2GB of RAM
db.pragma("cache_size = -32000"); // 32MB internal cache
db.pragma("mmap_size = 268435456"); // 256MB memory-mapped I/O (safe for 2GB server)
