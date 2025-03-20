# gptel-chatbotui

Use cookies to access chatbotui.

https://github.com/karthink/gptel/pull/280

```
(defvar gptel--chatbotui (gptel-make-chatbotui "Chatbot-ui"
                                                   :host "example.com"
                                                   :curl-args '("-k")
                                                   :protocol "https"
                                                   :endpoint "/api/chat"
                                                   :stream t
                                                   :header `(("Cookie" . ,(auth-source-pick-first-password :host "chatbot-ui-cookie")))
                                                   :models '(gpt-4o)))

(setq-default gptel-backend gptel--chatbotui)
(setq-default gptel-model 'gpt-4o)
```
