const express = require('express');
const router = express.Router();

// Integrations routes placeholder
router.get('/', (req, res) => {
  res.status(501).json({ message: 'Get integrations not implemented yet' });
});

router.post('/google/connect', (req, res) => {
  res.status(501).json({ message: 'Google integration not implemented yet' });
});

router.post('/airtable/connect', (req, res) => {
  res.status(501).json({ message: 'Airtable integration not implemented yet' });
});

router.delete('/:id', (req, res) => {
  res.status(501).json({ message: 'Delete integration not implemented yet' });
});

router.get('/:id/status', (req, res) => {
  res.status(501).json({ message: 'Integration status not implemented yet' });
});

module.exports = router;