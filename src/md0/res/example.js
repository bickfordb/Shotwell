(function() {
  document.innerHTML = "";
  var s = document.createElement("script");
  s.src = "http://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js";
  s.type = "text/javascript";
  s.onload = function() { 
    console.log('loaded');
    $(function() {
      $("body").html("<h1>whats up</h1>");
    });
  };
  var head = document.getElementsByTagName("head")[0];
  var body = document.getElementsByTagName("body")[0];
  head.appendChild(s);
  body.innerHTML = "<h1>bye</h1>";
  return 1;
})();
