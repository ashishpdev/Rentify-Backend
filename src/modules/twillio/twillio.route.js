// routes -- Routing / HTTP surface
const express = require("express");
const twillioController = require("./twillio.controller");
const router = express.Router();

// ====================== SEND MESSAGE (WhatsApp → SMS fallback) ======================
router.post("/send-message", twillioController.sendMessage);

// If later you want additional routes (templates, media):
// router.post("/send-template", requireAccessToken, twillioController.sendTemplate);
// router.post("/send-media", requireAccessToken, twillioController.sendMedia);

module.exports = router;
