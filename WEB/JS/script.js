document.addEventListener('DOMContentLoaded', function() {
    const mobileMenuBtn = document.getElementById('mobile-menu-btn');
    const mainNav = document.getElementById('main-nav');
    
    mobileMenuBtn.addEventListener('click', function() {
        mainNav.classList.toggle('active');
        
        const icon = this.querySelector('i');
        if (icon.classList.contains('fa-bars')) {
            icon.classList.remove('fa-bars');
            icon.classList.add('fa-times');
        } else {
            icon.classList.remove('fa-times');
            icon.classList.add('fa-bars');
        }
    });
    
    const navLinks = document.querySelectorAll('#main-nav a');
    navLinks.forEach(link => {
        link.addEventListener('click', function() {
            if (window.innerWidth <= 768) {
                mainNav.classList.remove('active');
                const icon = mobileMenuBtn.querySelector('i');
                icon.classList.remove('fa-times');
                icon.classList.add('fa-bars');
            }
        });
    });
    
    const themeToggleBtn = document.getElementById('theme-toggle-btn');
    const themeIcon = themeToggleBtn.querySelector('i');
    
    const savedTheme = localStorage.getItem('theme');
    if (savedTheme === 'dark') {
        document.body.classList.add('dark-mode');
        themeIcon.classList.remove('fa-moon');
        themeIcon.classList.add('fa-sun');
    }
    
    themeToggleBtn.addEventListener('click', function() {
        document.body.classList.toggle('dark-mode');
        
        if (themeIcon.classList.contains('fa-moon')) {
            themeIcon.classList.remove('fa-moon');
            themeIcon.classList.add('fa-sun');
            localStorage.setItem('theme', 'dark');
        } else {
            themeIcon.classList.remove('fa-sun');
            themeIcon.classList.add('fa-moon');
            localStorage.setItem('theme', 'light');
        }
    });
    
    const downloadButton = document.getElementById('download-button');
    const downloadStatus = document.getElementById('download-status');
    checkGameAvailability();
    
    function checkGameAvailability() {
        setTimeout(() => {
            const isAvailable = Math.random() > 0.5;
            
            if (isAvailable) {
                downloadButton.classList.remove('disabled');
                downloadStatus.textContent = "A játék elérhető letöltésre!";
                downloadStatus.style.color = "#4CAF50";
            } else {
                downloadButton.classList.add('disabled');
                downloadButton.textContent = "Hamarosan elérhető";
                downloadStatus.textContent = "A játék jelenleg fejlesztés alatt áll. Nézz vissza később!";
                downloadStatus.style.color = "#F44336";
            }
        }, 1000);
    }
    
    downloadButton.addEventListener('click', function(e) {
        if (this.classList.contains('disabled')) {
            e.preventDefault();
            alert('A játék jelenleg nem elérhető letöltésre. Kérjük, nézz vissza később!');
        } else {
            console.log('Download initiated');
        }
    });
    
    setInterval(checkGameAvailability, 300000);
    
    function setViewportHeight() {
        let vh = window.innerHeight * 0.01;
        document.documentElement.style.setProperty('--vh', `${vh}px`);
    }

    setViewportHeight();
    window.addEventListener('resize', setViewportHeight);

    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function(e) {
            e.preventDefault();
            
            const targetId = this.getAttribute('href');
            const targetElement = document.querySelector(targetId);
            
            if (targetElement) {
                window.scrollTo({
                    top: targetElement.offsetTop - 80,
                    behavior: 'smooth'
                });
            }
        });
    });
});