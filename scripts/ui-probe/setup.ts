// The probe must measure the app's real stylesheet, tokens and all, and the
// app is dark-first — `index.html` ships `class="dark"` on <html>. Anything
// less and every contrast measurement in Module C is taken against the wrong
// palette.
import '../../src/App.css';

document.documentElement.classList.add('dark');
document.documentElement.style.colorScheme = 'dark';
