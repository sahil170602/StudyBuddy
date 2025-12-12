import express from "express";
import cors from "cors";
import bodyParser from "body-parser";
import multer from "multer";
import Tesseract from "tesseract.js";
import axios from "axios";
import fs from "fs";
import path from "path";
import dotenv from "dotenv";

dotenv.config();

const app = express();
app.use(cors());
app.use(bodyParser.json({ limit: "30mb" }));
app.use(bodyParser.urlencoded({ extended: true, limit: "30mb" }));

// Multer upload folder
const upload = multer({ dest: "uploads/" });

const PORT = process.env.PORT || 3000;
const GEMINI_KEY = process.env.GEMINI_API_KEY;

// -----------------------------
// HEALTH CHECK
// -----------------------------
app.get("/api/health", (req, res) => {
  res.json({ ok: true, time: Date.now() });
});

// -----------------------------
// CHAT WITH GEMINI
// -----------------------------
app.post("/api/chat", async (req, res) => {
  try {
    const { message } = req.body;

    const response = await axios.post(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=" + GEMINI_KEY,
      {
        contents: [{ parts: [{ text: message }] }]
      }
    );

    const reply = response.data.candidates?.[0]?.content?.parts?.[0]?.text || "No reply";

    res.json({ reply });
  } catch (err) {
    console.error("Chat error:", err.response?.data || err.message);
    res.status(500).json({ error: "Chat failed" });
  }
});

// -----------------------------
// OCR SERVICE (IMAGE → TEXT)
// -----------------------------
app.post("/api/ocr", upload.single("file"), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: "File missing" });

    const result = await Tesseract.recognize(req.file.path, "eng");
    fs.unlinkSync(req.file.path); // cleanup temp file

    res.json({ text: result.data.text });
  } catch (e) {
    console.error("OCR error:", e.message);
    res.status(500).json({ error: "OCR failed" });
  }
});

// -----------------------------
// QUIZ GENERATION USING GEMINI
// -----------------------------
app.post("/api/quiz", async (req, res) => {
  try {
    const { syllabus, count } = req.body;

    const prompt = `
Generate ${count} MCQ quiz questions.
Each question must be JSON:
{
  "question": "...",
  "options": ["A", "B", "C", "D"],
  "correctIndex": 1
}
Syllabus:
${syllabus}
    `;

    const response = await axios.post(
      "https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=" + GEMINI_KEY,
      {
        contents: [{ parts: [{ text: prompt }] }]
      }
    );

    const raw = response.data.candidates?.[0]?.content?.parts?.[0]?.text || "[]";
    let quiz;

    try {
      quiz = JSON.parse(raw);
    } catch {
      // attempt extracting JSON
      const match = raw.match(/\[[\s\S]*\]/);
      quiz = match ? JSON.parse(match[0]) : [];
    }

    res.json({ quiz });
  } catch (err) {
    console.error("Quiz error:", err.message);
    res.status(500).json({ error: "Quiz generation failed" });
  }
});

// -----------------------------
// START SERVER
// -----------------------------
app.listen(PORT, () => {
  console.log(`StudyBuddy AI backend running on port ${PORT}`);
});
