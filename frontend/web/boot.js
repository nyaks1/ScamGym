// Remove the boot screen once Flutter has painted its first frame.
window.addEventListener('flutter-first-frame', function () {
  var boot = document.getElementById('boot');
  if (boot) {
    boot.style.transition = 'opacity 180ms ease';
    boot.style.opacity = '0';
    setTimeout(function () {
      if (boot.parentNode) boot.parentNode.removeChild(boot);
    }, 200);
  }
});
