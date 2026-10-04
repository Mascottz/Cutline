document.addEventListener("DOMContentLoaded", function () {
  var root = document.getElementById("cutline");
  if (window.Elm && root) {
    window.Elm.Main.init({ node: root });
  }
});
