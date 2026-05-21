import "./style.css";
import { generateSeeds } from "./seedGenerator";

const sampleSchema = `ActiveRecord::Schema[8.0].define(version: 2026_05_21_120000) do
  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "posts", force: :cascade do |t|
    t.string "title"
    t.text "body"
    t.integer "user_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "comments", force: :cascade do |t|
    t.text "body"
    t.integer "post_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "posts", "users"
  add_foreign_key "comments", "posts"
end`;

const schemaInput = requiredElement<HTMLTextAreaElement>("schema-input");
const seedOutput = requiredElement<HTMLTextAreaElement>("seed-output");
const generateButton = requiredElement<HTMLButtonElement>("generate-button");
const sampleButton = requiredElement<HTMLButtonElement>("sample-button");
const copyButton = requiredElement<HTMLButtonElement>("copy-button");
const message = requiredElement<HTMLParagraphElement>("message");

schemaInput.value = sampleSchema;
generate();

generateButton.addEventListener("click", generate);

schemaInput.addEventListener("keydown", (event) => {
  if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
    generate();
  }
});

sampleButton.addEventListener("click", () => {
  schemaInput.value = sampleSchema;
  generate();
});

copyButton.addEventListener("click", async () => {
  if (seedOutput.value.trim() === "") {
    setMessage("Generate a seed file first.", "error");
    return;
  }

  await navigator.clipboard.writeText(seedOutput.value);
  setMessage("Copied seeds.rb output.", "success");
});

function generate(): void {
  try {
    seedOutput.value = generateSeeds(schemaInput.value);
    setMessage("Generated seeds.rb output.", "success");
  } catch (error) {
    seedOutput.value = "";
    setMessage(error instanceof Error ? error.message : "Could not generate seeds.", "error");
  }
}

function setMessage(text: string, status: "success" | "error"): void {
  message.textContent = text;
  message.dataset.status = status;
}

function requiredElement<T extends HTMLElement>(id: string): T {
  const element = document.getElementById(id);

  if (!element) {
    throw new Error(`Missing #${id}`);
  }

  return element as T;
}
