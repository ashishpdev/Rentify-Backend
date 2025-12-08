const router = require("express").Router();
const WhatsappController = require("./whatsapp.controller");

router.get("/qr/:businessId", WhatsappController.generateQR);     // get qr json
router.get("/status/:businessId", WhatsappController.getStatus); // return connection state
router.post("/send/:businessId", WhatsappController.sendMessage);
router.delete("/logout/:businessId", WhatsappController.logout); // remove session


module.exports = router;
