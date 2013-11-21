var es = new EventSource('/chat-stream');


es.onmessage = function(e){
    var chat = $("#chat");
    var content = $('<p>');
    content.append(e.data);
    chat.append(content);
    chat.append(content);
    var height = $("#chat").children().length;
    $("#chat").scrollTop(height * 1000);
};

$("#chat-submit").live("submit", function(e){
    var messages_box = $("#message");
    $.post('/chat', {
        message: $('#message').val()
    });
    messages_box.val('');
    messages_box.focus();
    e.preventDefault();
});

var user_source = new EventSource('/chat-users');

user_source.onmessage = function(e){
    var users_div = $("#users");
    
    users_div.empty();
    var list = $("<ul>");
    users_div.append(list);
    
    names = JSON.parse(e.data);
    
    for (var i = 0; i < names.num; i++) {
        list.append($("<li>").text(names.users[i]));
    }
};
