const { calendar_list, calendar_get, reminders_create, NOW, TIMEZONE } = window;

function getAttendeeName(id) {
  const event = calendar_get({ id });
  if (!event) return null;
  const attendees = event.attendees || [];
  return attendees.find(a => a.role === 'attendee')?.name || null;
}

function getTodayDate() {
  const today = new Date();
  const dateStr = today.toISOString().split('T')[0];
  return { date: dateStr };
}

function getTomorrowDate() {
  const today = new Date();
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  const dateStr = tomorrow.toISOString().split('T')[0];
  return { date: dateStr };
}

function createReminder() {
  const today = getTodayDate();
  const tomorrow = getTomorrowDate();
  const attendeeName = getAttendeeName(today.date);

  if (!attendeeName) {
    console.log("No attendee found for today's meeting.");
    return;
  }

  const due = new Date(NOW);
  due.setHours(9, 0, 0, 0);
  const dueStr = due.toISOString().replace('T', ' ').replace('+00:00', '');

  const reminder = {
    title: `${attendeeName} - Follow-up`,
    due: dueStr,
    notes: `Meeting with ${attendeeName} today. Follow-up notes to be sent.`
  };

  reminders_create(reminder);
  console.log(`Reminder created for ${attendeeName} at ${dueStr}.`);
}

createReminder();