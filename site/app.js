const copyStatus = document.querySelector("#copy-status");
const resetTimers = new WeakMap();

document.querySelectorAll(".mobile-nav a").forEach((link) => {
  link.addEventListener("click", () => link.closest("details")?.removeAttribute("open"));
});

const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
if (!reducedMotion.matches && "IntersectionObserver" in window) {
  const revealItems = document.querySelectorAll(
    ".release-heading, .release-checks, .section-heading, .single-command, .warning, .steps li, .command-grid article, .result-list li, .tag-list li, .architecture iframe, .diagram-link",
  );

  revealItems.forEach((item, index) => {
    item.classList.add("reveal");
    item.style.setProperty("--reveal-delay", `${(index % 4) * 55}ms`);
  });
  document.documentElement.classList.add("reveal-ready");

  const revealObserver = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add("is-visible");
        revealObserver.unobserve(entry.target);
      });
    },
    { rootMargin: "0px 0px -10%", threshold: 0.08 },
  );

  revealItems.forEach((item) => revealObserver.observe(item));
}

const releasePanel = document.querySelector("#release");
fetch("release.json", { cache: "no-store" })
  .then((response) => {
    if (!response.ok) throw new Error(`release metadata returned ${response.status}`);
    return response.json();
  })
  .then((release) => {
    document.querySelector("#release-version").textContent = `v${release.version}`;
    document.querySelector("#native-checksum").textContent = release.native_sha256;
    document.querySelector("#source-checksum").textContent = release.source_sha256;
    document.querySelector("#release-download").href = release.native_url;
    document.querySelector("#checksum-file").href = release.native_checksum_url;
    releasePanel.dataset.releaseState = "ready";
  })
  .catch(() => {
    document.querySelector("#release-version").textContent = "See GitHub releases";
    releasePanel.dataset.releaseState = "error";
  });

document.querySelectorAll(".copy").forEach((button) => {
  button.addEventListener("click", async () => {
    const code = button.previousElementSibling;
    const command = code?.textContent;
    if (!command || !code) return;

    window.clearTimeout(resetTimers.get(button));

    try {
      await navigator.clipboard.writeText(command);
      button.textContent = "Copied";
      if (copyStatus) copyStatus.textContent = "Command copied.";
    } catch {
      const range = document.createRange();
      range.selectNodeContents(code);
      const selection = window.getSelection();
      selection?.removeAllRanges();
      selection?.addRange(range);
      code.focus();
      button.textContent = "Selected";
      if (copyStatus) copyStatus.textContent = "Copy was unavailable. The command is selected. Press Control+C to copy it.";
    }

    const timer = window.setTimeout(() => { button.textContent = "Copy"; }, 1600);
    resetTimers.set(button, timer);
  });
});
