const express = require('express');
const multer = require('multer');
const router = express.Router();
const { 
  controller, 
  processVoiceValidation, 
  processVoiceAudioValidation, 
  processTextValidation,
  synthesizeSpeechValidation 
} = require('../controllers/voice.controller');
const { authenticateToken } = require('../services/auth/middleware');

// Configure multer for audio file uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB limit
  fileFilter: (req, file, cb) => {
    if (file.mimetype.startsWith('audio/')) {
      cb(null, true);
    } else {
      cb(new Error('Only audio files are allowed'), false);
    }
  }
});

// Development-only endpoint
router.post('/dev/process-audio', upload.single('audio'), processVoiceAudioValidation, controller.processVoiceAudio.bind(controller));

// Voice processing routes (authentication handled by app.js)
router.post('/process-text', processTextValidation, controller.processText.bind(controller));
router.post('/process', processVoiceValidation, controller.processVoiceCommand.bind(controller));
router.post('/process-audio', upload.single('audio'), processVoiceAudioValidation, controller.processVoiceAudio.bind(controller));

// Async voice processing routes (using queue)
router.post('/process-async', processVoiceValidation, controller.processVoiceCommandAsync.bind(controller));
router.post('/process-audio-async', upload.single('audio'), processVoiceAudioValidation, controller.processVoiceAudioAsync.bind(controller));
router.get('/job/:jobId', controller.getJobStatus.bind(controller));

// Speech-to-text and text-to-speech routes
router.post('/transcribe', upload.single('audio'), controller.transcribeAudio.bind(controller));
router.post('/synthesize', synthesizeSpeechValidation, controller.synthesizeSpeech.bind(controller));
router.get('/voices', controller.getAvailableVoices.bind(controller));

// Voice command management routes
router.get('/history', controller.getVoiceHistory.bind(controller));
router.get('/conversations', controller.getConversationHistory.bind(controller));
router.delete('/conversations', controller.clearConversationHistory.bind(controller));
router.get('/context', controller.getUserContext.bind(controller));
router.get('/stats', controller.getVoiceStats.bind(controller));
router.get('/analytics', controller.getTranscriptionAnalytics.bind(controller));

// Streaming routes for real-time processing
router.post('/stream-start', controller.streamStart.bind(controller));
router.post('/stream-process', controller.streamProcess.bind(controller));
router.post('/stream-end', controller.streamEnd.bind(controller));

module.exports = router;