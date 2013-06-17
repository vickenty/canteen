$(function() {

	$("#votelist .push_button").bind('touchstart', function () {
		$(this).parent().find('.push_button').removeClass('active');
		$(this).parent().find('input:radio').attr('checked','');
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