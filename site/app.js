const copyStatus = document.querySelector("#copy-status");
const resetTimers = new WeakMap();

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
