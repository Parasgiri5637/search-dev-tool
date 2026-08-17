(function () {
  const vscode = acquireVsCodeApi();

  const queryInput = document.getElementById('query-input');
  const submitBtn = document.getElementById('submit-btn');
  const refreshBtn = document.getElementById('refresh-btn');
  const suggestedChips = document.getElementById('suggested-chips');
  const projectStats = document.getElementById('project-stats');
  const loadingIndicator = document.getElementById('loading-indicator');
  const loadingText = document.getElementById('loading-text');
  const errorBanner = document.getElementById('error-banner');
  const errorMessage = document.getElementById('error-message');

  const resultsSection = document.getElementById('results-section');
  const resultTitle = document.getElementById('result-title');
  const resultIntentBadge = document.getElementById('result-intent-badge');
  const resultFileWrapper = document.getElementById('result-file-wrapper');
  const resultFileLink = document.getElementById('result-file-link');
  const resultSummary = document.getElementById('result-summary');

  const flowContainer = document.getElementById('flow-container');
  const flowSteps = document.getElementById('flow-steps');

  const dependsOnCard = document.getElementById('depends-on-card');
  const dependsOnList = document.getElementById('depends-on-list');
  const callsCard = document.getElementById('calls-card');
  const callsList = document.getElementById('calls-list');
  const usedByCard = document.getElementById('used-by-card');
  const usedByList = document.getElementById('used-by-list');

  const followupsWrapper = document.getElementById('followups-wrapper');
  const followupChips = document.getElementById('followup-chips');

  // Submit Query
  function submitQuery(queryText) {
    const q = (queryText || queryInput.value || '').trim();
    if (!q) return;

    queryInput.value = q;
    showLoading(`Answering: "${q}"...`);
    hideError();

    vscode.postMessage({
      command: 'query',
      query: q,
    });
  }

  submitBtn.addEventListener('click', () => submitQuery());
  queryInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      submitQuery();
    }
  });

  refreshBtn.addEventListener('click', () => {
    showLoading('Re-indexing workspace...');
    vscode.postMessage({ command: 'refresh' });
  });

  suggestedChips.addEventListener('click', (e) => {
    const chip = e.target.closest('.chip');
    if (chip && chip.dataset.query) {
      submitQuery(chip.dataset.query);
    }
  });

  function showLoading(msg) {
    loadingText.textContent = msg || 'Loading...';
    loadingIndicator.classList.remove('hidden');
  }

  function hideLoading() {
    loadingIndicator.classList.add('hidden');
  }

  function showError(msg) {
    errorMessage.textContent = msg;
    errorBanner.classList.remove('hidden');
    hideLoading();
  }

  function hideError() {
    errorBanner.classList.add('hidden');
  }

  function openFile(filePath, line, column) {
    vscode.postMessage({
      command: 'openFile',
      filePath: filePath,
      line: line,
      column: column,
    });
  }

  // Render Result
  function renderResult(res) {
    hideLoading();
    hideError();

    resultsSection.classList.remove('hidden');
    resultTitle.textContent = res.title || 'Result';
    resultIntentBadge.textContent = (res.intent || '').replace('_', ' ');
    resultSummary.textContent = res.summary || '';

    // File Link
    if (res.sourceLocation && res.sourceLocation.filePath) {
      resultFileWrapper.classList.remove('hidden');
      const locStr = `${res.sourceLocation.filePath}:${res.sourceLocation.line}`;
      resultFileLink.textContent = locStr;
      resultFileLink.onclick = (e) => {
        e.preventDefault();
        openFile(
          res.sourceLocation.filePath,
          res.sourceLocation.line,
          res.sourceLocation.column
        );
      };
    } else {
      resultFileWrapper.classList.add('hidden');
    }

    // Call Flow Chain (Milestone 11)
    if (res.callChain && res.callChain.length > 1) {
      flowContainer.classList.remove('hidden');
      flowSteps.innerHTML = '';
      res.callChain.forEach((step, idx) => {
        const stepEl = document.createElement('span');
        stepEl.className = 'flow-step-node';
        stepEl.textContent = step;
        stepEl.onclick = () => submitQuery(`Where is ${step}?`);
        flowSteps.appendChild(stepEl);

        if (idx < res.callChain.length - 1) {
          const arrow = document.createElement('span');
          arrow.className = 'flow-arrow';
          arrow.textContent = '→';
          flowSteps.appendChild(arrow);
        }
      });
    } else {
      flowContainer.classList.add('hidden');
    }

    // Depends on
    renderRelationList(dependsOnCard, dependsOnList, res.dependsOn, '→ ');

    // Calls
    renderRelationList(callsCard, callsList, res.calls, '→ ');

    // Used by
    renderRelationList(usedByCard, usedByList, res.usedBy, '← ');

    // Followup chips
    if (res.suggestedFollowups && res.suggestedFollowups.length > 0) {
      followupsWrapper.classList.remove('hidden');
      followupChips.innerHTML = '';
      res.suggestedFollowups.forEach((f) => {
        const btn = document.createElement('button');
        btn.className = 'chip';
        btn.textContent = f;
        btn.onclick = () => submitQuery(f);
        followupChips.appendChild(btn);
      });
    } else {
      followupsWrapper.classList.add('hidden');
    }
  }

  function renderRelationList(cardEl, listEl, items, prefix) {
    if (items && items.length > 0) {
      cardEl.classList.remove('hidden');
      listEl.innerHTML = '';
      items.forEach((item) => {
        const li = document.createElement('li');
        li.className = 'relation-item';
        li.textContent = `${prefix}${item.label}`;
        li.onclick = () => {
          if (item.location && item.location.filePath) {
            openFile(
              item.location.filePath,
              item.location.line,
              item.location.column
            );
          } else {
            submitQuery(`Where is ${item.label}?`);
          }
        };
        listEl.appendChild(li);
      });
    } else {
      cardEl.classList.add('hidden');
    }
  }

  // Handle Extension Messages
  window.addEventListener('message', (event) => {
    const msg = event.data;
    switch (msg.type) {
      case 'indexing':
        showLoading(msg.message);
        break;
      case 'indexed':
        hideLoading();
        if (msg.data && msg.data.summary) {
          const s = msg.data.summary;
          projectStats.textContent = `${s.files} files · ${s.classes} classes · ${s.methods} methods`;
        }
        break;
      case 'queryLoading':
        showLoading('Querying knowledge graph...');
        break;
      case 'queryResult':
        renderResult(msg.result);
        break;
      case 'queryError':
        showError(msg.message);
        break;
      case 'error':
        showError(msg.message);
        break;
      case 'status':
        projectStats.textContent = msg.status;
        break;
    }
  });

  // Notify extension that webview is ready
  vscode.postMessage({ command: 'ready' });
})();
