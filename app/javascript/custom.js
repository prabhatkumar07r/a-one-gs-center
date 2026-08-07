
     const notificationsData = [
    {
      title: "New Batch Starting Soon",
      desc: "We are starting a new batch for Intermediate Art's from next Monday. Limited seats available.",
      date: "February 25, 2026",
      icon: "fa-bullhorn"
    },
    {
      title: "Special Weekend Classes",
      desc: "Special weekend classes for Chemistry practicals will begin from October 1st.",
      date: "September 20, 2023",
      icon: "fa-calendar-week"
    },
    {
      title: "Parent-Teacher Meeting",
      desc: "Quarterly parent-teacher meeting scheduled on October 5th at 4:00 PM.",
      date: "September 18, 2023",
      icon: "fa-chalkboard-user"
    },
    // Extra notification to make scroll richer (from original vibe)
    {
      title: "Exam Form Notice",
      desc: "Last date to submit examination forms is October 15th, 2023.",
      date: "October 01, 2023",
      icon: "fa-file-alt"
    }
  ];

  // Helper: escape HTML
  function escapeHtml(str) {
    if (!str) return '';
    return str.replace(/[&<>]/g, function(m) {
      if (m === '&') return '&amp;';
      if (m === '<') return '&lt;';
      if (m === '>') return '&gt;';
      return m;
    });
  }

  // Build ticker with 2 cycles for seamless infinite horizontal scroll
  function buildTicker() {
    const ticker = document.getElementById('notificationTicker');
    if (!ticker) return;
    ticker.innerHTML = '';
    
    // 2 cycles to make translateX(-50%) work seamlessly
    const cycles = 2;
    for (let cycle = 0; cycle < cycles; cycle++) {
      notificationsData.forEach(notif => {
        const notifDiv = document.createElement('div');
        notifDiv.className = 'ticker-notification';
        const iconClass = notif.icon || "fa-bullhorn";
        notifDiv.innerHTML = `
          <i class="fas ${iconClass}"></i>
          <div class="ticker-content">
            <strong>${escapeHtml(notif.title)}</strong>
            <p>${escapeHtml(notif.desc)}</p>
            <span class="ticker-date"><i class="far fa-calendar-alt"></i> Posted on: ${escapeHtml(notif.date)}</span>
          </div>
        `;
        ticker.appendChild(notifDiv);
      });
    }
  }

  // Global reference
  let tickerTrack = null;
  let currentSpeed = 35;

  // Function to dynamically add new notification (keeps infinite scroll alive)
  window.addLiveNotification = function(title, message, date, icon = 'fa-bullhorn') {
    if (!tickerTrack) return;
    const newItem = document.createElement('div');
    newItem.className = 'ticker-notification';
    newItem.innerHTML = `
      <i class="fas ${icon}"></i>
      <div class="ticker-content">
        <strong>${escapeHtml(title)}</strong>
        <p>${escapeHtml(message)}</p>
        <span class="ticker-date"><i class="far fa-calendar-alt"></i> Posted on: ${escapeHtml(date)}</span>
      </div>
    `;
    tickerTrack.appendChild(newItem);
    // No restart needed — animation continues seamlessly
  };

  // Initialize ticker
  function init() {
    buildTicker();
    tickerTrack = document.getElementById('notificationTicker');
    if (!tickerTrack) return;
    
    // Apply animation
    tickerTrack.style.animation = `scrollHorizontalFlow 35s linear infinite`;
    tickerTrack.style.willChange = 'transform';
    
    // Handle window resize to keep animation smooth
    window.addEventListener('resize', function() {
      if (tickerTrack) {
        tickerTrack.style.animation = `scrollHorizontalFlow ${currentSpeed}s linear infinite`;
      }
    });
    
    // Optional: Auto add fresh notifications periodically to simulate live updates
    setTimeout(() => {
      if (window.addLiveNotification) {
        window.addLiveNotification("📢 Workshop Alert", "Free workshop on Web Development on October 25th.", "October 10, 2023", "fa-laptop-code");
      }
    }, 8000);
    
    setTimeout(() => {
      if (window.addLiveNotification) {
        window.addLiveNotification("🏆 Cultural Fest", "Annual fest 'Utsav 2023' from November 5th to 7th.", "October 12, 2023", "fa-music");
      }
    }, 15000);
  }
  
  // Start after DOM ready
  document.addEventListener('DOMContentLoaded', init);