(function() {
    'use strict';
    try {
        document.addEventListener("contextmenu", function(e) {
            console.log("contextmenu detected");
            if (!e.isTrusted) {
                console.log("Non-trusted context menu. Ignore.");
                return;
            }
            if (e.altKey) {
                // We originated this event so allow it to go through. Unfortuantely the more obscure modifiers aren't passed through.
                console.log("Seems to be originated by us.");
                return;
            }
            e.preventDefault();
            window.webkit.messageHandlers.iTermContextMenuMonitor.postMessage({
                sessionSecret: "{{SECRET}}",
                x: e.clientX,
                y: e.clientY,
                selection: window.getSelection().toString()
            });
        });
    } catch (err) {
        console.error(
            '[monitor-selection error]',
            'message:', err.message,
            'stack:', err.stack
        );
    }
    return true;
})();
