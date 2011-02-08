$.noConflict();

jQuery(function(){
    jQuery('.download-link').click(function(e){
        console.log('clicking. . .');
        var file_id = jQuery(this).attr('id').split('-')[1];
        jQuery.ajax({
            type: 'POST',
            cache: false,
            data: {rm: 'click', id: file_id}
        });
    });
});
