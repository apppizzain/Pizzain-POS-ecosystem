const LINKS = {
  menu: "https://drive.google.com/file/d/1nEDGxb90NJI3LRCGiLe1j5v6masHLb4o/view",
  delivery: "https://wa.me/6282210069671?text=Assalamualaikum%20Pizzain%2C%20saya%20mau%20pesan%20delivery",
  takeaway: "https://wa.me/6281285601788?text=Halo%20Pizzain%2C%20saya%20mau%20pesan%20takeaway",
  feedback: "https://wa.me/6282310946757?text=Halo%20Pizzain%2C%20saya%20mau%20memberi%20kritik%20dan%20saran",
};

document.querySelectorAll("[data-link-key]").forEach((button) => {
  const key = button.dataset.linkKey;
  const target = LINKS[key];

  if (target) {
    button.href = target;
  }

  button.addEventListener("pointerdown", () => {
    button.classList.add("is-pressed");
  });

  const releasePress = () => {
    window.setTimeout(() => button.classList.remove("is-pressed"), 120);
  };

  button.addEventListener("pointerup", releasePress);
  button.addEventListener("pointercancel", releasePress);
  button.addEventListener("pointerleave", releasePress);
});
