document.addEventListener('DOMContentLoaded', () => {
    const hamburgerButton = document.getElementById('hamburger-button');
    const navigationLinks = document.getElementById('navigation-links');

    hamburgerButton.addEventListener('click', () => {
        navigationLinks.classList.toggle('hidden');
        navigationLinks.classList.toggle('flex');
        navigationLinks.classList.toggle('flex-col'); // Ensure vertical stacking on mobile
        navigationLinks.classList.toggle('w-full'); // Ensure it takes full width on mobile
    });
});
