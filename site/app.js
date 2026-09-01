document.documentElement.classList.add("js");

const copyStatus = document.querySelector("#copy-status");
const resetTimers = new WeakMap();

document.querySelectorAll(".mobile-nav a").forEach((link) => {
  link.addEventListener("click", () => link.closest("details")?.removeAttribute("open"));
});

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
    releasePanel.dataset.releaseState = "ready";
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
