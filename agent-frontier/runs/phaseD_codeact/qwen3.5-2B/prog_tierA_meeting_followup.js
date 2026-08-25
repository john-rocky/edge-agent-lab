const { calendar_list, calendar_get, reminders_create, NOW, TIMEZONE } = {};

function getLocalTime() {
  const now = new Date(NOW);
  const tz = new Date(TIMEZONE);
  const offset = tz.getTimezoneOffset() * 60000;
  return new Date(now.getTime() - offset);
}

function getAttendeeName() {
  const today = new Date();
  const dayEvents = calendar_list({ date: today.toISOString().split('T')[0] });
  const attendee = dayEvents.find(e => e.attendee);
  return attendee ? attendee.name : "Unknown";
}

function createFollowUpReminder() {
  const now = getLocalTime();
  const tomorrow = new Date(now);
  tomorrow.setDate(tomorrow.getDate() + 1);
  tomorrow.setHours(9, 0, 0, 0);
  const iso = tomorrow.toISOString();
  const title = `Follow-up: ${getAttendeeName()}`;
  const reminder = reminders_create({ title, due: iso });
  console.log("Reminder created:", reminder);
}

createFollowUpReminder();