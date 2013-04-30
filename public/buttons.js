$(".button_container").live("touchstart", 
	function() {
      	$('#submit_button').addClass("active");
      	
      	}).live("touchend", 
      		function() {
	      		$('#submit_button').removeClass("active");
	      	}
	      );
