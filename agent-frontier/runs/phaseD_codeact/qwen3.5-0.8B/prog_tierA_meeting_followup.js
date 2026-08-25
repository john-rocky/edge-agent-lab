// Get current time in ISO8601 format with timezone offset
const now = new Date();
const timeZone = new Intl.DateTimeFormat('en-US', { timeZone: 'UTC', hour: '2-digit', minute: '2-digit' }).format(now);
const nowStr = now.toISOString().replace('Z', '+00:00');

// Get today's events
const todayEvents = calendar_list({ date: '2024-01-15' });

// Get attendee name from attendee list
const attendees = todayEvents.filter(e => e.attendee);
const attendeeName = attendees[0].attendee;

// Create reminder for tomorrow at 9:00 AM
const tomorrow = new Date(now.getTime() + 86400000);
const tomorrowStr = tomorrow.toISOString().replace('Z', '+00:00');

const reminder = {
  title: `Follow-up Note: ${attendeeName} - ${timeZone}`,
  due: tomorrowStr,
  notes: `Meeting ended today. Sending follow-up to ${attendeeName}.`
};

// Create reminder
const reminders = reminders_create(reminder);

// Print the answer
console.log(`Reminder created: ${reminder.title}`);