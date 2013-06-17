$(function() {

	$("#votelist .push_button").bind('touchstart', function () {
	
		// remove active class from all inputs within a meal type 
		// (go to parent, then identify all labels, remove class 'active' then all radios and deselect all)
		$(this).parent().find('.push_button').removeClass('active');
		$(this).parent().find('input:radio').removeAttr('checked');

		// add 'active' class and select input on current element
		$(this).addClass('active');
		$(this).find('input:radio').attr('checked','checked');
	});

	
	$("#submit_button").click ( function () {
		$(this).addClass('pushed_in');	
	});
		
	
	setTimeout(function() {
	  var $button = $('#submit_button');
	  $button.text($button.data('normal'));
	}, 3000);

});