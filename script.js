const galleryItems = [
  { ar: "آيس لاتيه", en: "", img:"image.3.jpg" },
  { ar: "تكة دجاج", en: "Chicken tikka", img:"تكة دجاج.jpg" },
  { ar: "لحم فرانشيسكو", en: "", img:"image.4.jpg" },
  { ar: "مشكل تكه ومعلاق", en: "", img:"image.5.jpg" },
  { ar: "موكتيل روز", en: "Rose mocktail", img:"image.6.jpg" },
  { ar: "سلطة فتوش", en: "Fattoush salad", img:"image.7.jpg" },
  { ar: "شرقي خواطر", en: "", img:"image.8.jpg" },
  { ar: "دجاج مسحب", en: "", img:"image.9.jpg" },
  { ar: "تفاح موهيتو", en: "", img:"image.10.jpg" },
  { ar: "اجنحة على فحم", en: "Grilled wings", img:"image.11.jpg" },
  { ar: "دولمة", en: "", img:"image.12.jpg" },
  { ar: "قوزي عراقي", en: "", img:"image.13.jpg" },
  { ar: "ميلك شيك شوكولاته", en: "", img:"image.14.jpg" },
  { ar: "ملك شيك فراولة", en: "", img:"image.15.jpg" },
  { ar: "ستيك مشروم", en: "", img:"image.16.jpg" },
  { ar: "بيتزا الحمر", en: "", img:"image.17.jpg" },
  { ar: "تشيز كيك بستاشيو", en: "Pistachio cheesecake", img:"image.18.jpg" },
  { ar: "كوكتيل بلو كرواسو", en: "Blue croissant cocktail", img:"image.19.jpg" },
  { ar: "طبق كبدة", en: "Liver dish", img:"image.20.jpg" },
  { ar: "بيدا الحمر", en: "", img:"image.21.jpg" },
  { ar: "تشيز كيك لوتس", en: "Lotus cheesecake", img:"image22.jpg" },
  { ar: "ستيك دجاج", en: "Chicken steak", img:"image.23.jpg" },
  { ar: "سكالوب لحم", en: "Meat scallop", img:"image.24.jpg" },
  { ar: "قهوة أمريكانو", en: "", img:"image.25.jpg" }
];

const WHATSAPP_NUMBER = "9647508188655";

function showPage(pageId) {
  document.querySelectorAll(".page").forEach(p => p.classList.remove("active-page"));
  const target = document.getElementById(pageId);
  if (target) target.classList.add("active-page");

  document.querySelectorAll(".nav-link").forEach(link => {
    link.classList.toggle("active", link.dataset.page === pageId);
  });

  window.scrollTo({ top: 0, behavior: "smooth" });
}

document.querySelectorAll(".nav-link").forEach(link => {
  link.addEventListener("click", (e) => {
    e.preventDefault();
    showPage(link.dataset.page);
  });
});

document.getElementById("bookNowBtn").addEventListener("click", () => showPage("booking"));
document.getElementById("reserveBtn").addEventListener("click", () => showPage("booking"));
document.getElementById("menuBtn").addEventListener("click", () => showPage("gallery"));

document.getElementById("hamburger").addEventListener("click", () => {
  const nav = document.getElementById("navLinks");
  nav.style.display = nav.style.display === "flex" ? "none" : "flex";
});

let selectedSeating = null;

document.querySelectorAll(".seating-card").forEach(card => {
  card.addEventListener("click", () => {
    document.querySelectorAll(".seating-card").forEach(c => c.classList.remove("selected"));
    card.classList.add("selected");
    selectedSeating = card.dataset.type;
  });
});

function goToStep(stepNum) {
  document.querySelectorAll(".booking-step").forEach(s => s.classList.remove("active-step"));
  document.getElementById("step" + stepNum).classList.add("active-step");
}

document.getElementById("toStep2").addEventListener("click", () => {
  if (!selectedSeating) {
    alert("يرجى اختيار نوع الجلسة أولاً");
    return;
  }
  goToStep(2);
});
document.getElementById("backToStep1").addEventListener("click", () => goToStep(1));
document.getElementById("toStep3").addEventListener("click", () => goToStep(3));
document.getElementById("backToStep2").addEventListener("click", () => goToStep(2));

document.getElementById("sendWhatsapp").addEventListener("click", () => {
  const name = document.getElementById("bookingName").value.trim();
  const phone = document.getElementById("bookingPhone").value.trim();
  const request = document.getElementById("bookingRequest").value.trim();
  const date = document.getElementById("bookingDate").value;
  const time = document.getElementById("bookingTime").value;
  const guests = document.getElementById("guestCount").value;

  if (!name || !phone) {
    alert("يرجى تعبئة الاسم ورقم الهاتف");
    return;
  }

  const message =
    `حجز طاولة - خواطر كافيه%0A` +
    `الاسم: ${name}%0A` +
    `الهاتف: ${phone}%0A` +
    `نوع الجلسة: ${selectedSeating || "-"}%0A` +
    `التاريخ: ${date || "-"}%0A` +
    `الوقت: ${time || "-"}%0A` +
    `عدد الأشخاص: ${guests || "-"}%0A` +
    `طلب مسبق: ${request || "-"}`;

  window.open(`https://wa.me/${WHATSAPP_NUMBER}?text=${message}`, "_blank");
});

document.getElementById("sendContactWhatsapp").addEventListener("click", () => {
  const name = document.getElementById("contactName").value.trim();
  const phone = document.getElementById("contactPhone").value.trim();
  const msg = document.getElementById("contactMessage").value.trim();

  if (!name || !phone) {
    alert("يرجى تعبئة الاسم ورقم الهاتف");
    return;
  }

  const message =
    `تواصل معنا - خواطر كافيه%0A` +
    `الاسم: ${name}%0A` +
    `الهاتف: ${phone}%0A` +
    `الرسالة: ${msg || "-"}`;

  window.open(`https://wa.me/${WHATSAPP_NUMBER}?text=${message}`, "_blank");
});

function renderGallery() {
  const grid = document.getElementById("galleryGrid");
  if(!grid) return;
  grid.innerHTML = galleryItems.map(item => `
    <div class="gallery-item">
      <img src="${item.img}" alt="${item.ar}" loading="lazy">
      <div class="gallery-caption">${item.ar}</div>
      ${item.en ? `<div class="gallery-caption-en">${item.en}</div>` : ""}
    </div>
  `).join("");
}

renderGallery();
showPage("home");