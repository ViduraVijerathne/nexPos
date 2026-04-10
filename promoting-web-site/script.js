const revealItems = document.querySelectorAll(".reveal");
const navShell = document.getElementById("nav-shell");

const revealObserver = new IntersectionObserver(
  entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        revealObserver.unobserve(entry.target);
      }
    });
  },
  {
    threshold: 0.18,
    rootMargin: "0px 0px -40px 0px",
  },
);

revealItems.forEach(item => revealObserver.observe(item));

const updateNavState = () => {
  if (!navShell) {
    return;
  }

  navShell.classList.toggle("is-scrolled", window.scrollY > 10);
};

window.addEventListener("scroll", updateNavState, { passive: true });
updateNavState();
