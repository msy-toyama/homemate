(function () {
  var KEY = 'hm-lang';
  function detect() {
    var s = localStorage.getItem(KEY);
    if (s === 'ja' || s === 'en') return s;
    return (navigator.language || 'en').toLowerCase().indexOf('ja') === 0 ? 'ja' : 'en';
  }
  function apply(l) {
    document.documentElement.setAttribute('data-lang', l);
    document.documentElement.lang = l;
    try { localStorage.setItem(KEY, l); } catch (e) {}
    var btns = document.querySelectorAll('.lang-switch button');
    for (var i = 0; i < btns.length; i++) {
      btns[i].classList.toggle('active', btns[i].getAttribute('data-set') === l);
    }
  }
  apply(detect());
  document.addEventListener('DOMContentLoaded', function () {
    apply(document.documentElement.getAttribute('data-lang') || detect());
  });
  document.addEventListener('click', function (e) {
    var t = e.target;
    while (t && t.tagName !== 'BUTTON') t = t.parentElement;
    if (t && t.parentElement && t.parentElement.classList.contains('lang-switch')) {
      apply(t.getAttribute('data-set'));
    }
  });
})();
