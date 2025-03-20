;;; gptel-chatbotui.el --- ChatbotUI support for gptel     -*- lexical-binding: t; -*-

;; Copyright (C) 2023  Damon Chan

;; Author: Damon Chan <elecming@gmail.com>
;; Keywords: hypermedia

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This file adds support for the ChatbotUI LLM API to gptel

;;; Code:
(require 'gptel)
(require 'cl-generic)

;;; ChatbotUI backend
(cl-defstruct (gptel-chatbotui (:constructor gptel--make-chatbotui)
                               (:copier nil)
                               (:include gptel-backend)))

(defvar-local gptel--chatbotui-context nil
  "Context for chatbotui conversations.
This variable holds the context array for conversations with
ChatbotUI models.")

;; Define parsing response methods here
(cl-defmethod gptel-curl--parse-stream ((_backend gptel-chatbotui) _info)
  "Parse streaming response from ChatbotUI."
  (when (bobp)
    (re-search-forward "\r\n\r\n")
    (forward-line 0))
  (let ((content "")
        (content-end (point-max)))
    (while (re-search-forward "\\(.+\\)$" content-end t) ; (re-search-forward "([a-f0-9]+ \\. [0-9]+)" nil t)
      (setq content (concat content "\n" (match-string 0))))
    ;; remove the final (4cfc131035f65027ad89312027fcb3d9 . 990)
    (replace-regexp-in-string "([a-f0-9]+ \\. [0-9]+)" "" content)))

(cl-defmethod gptel--parse-response ((_backend gptel-chatbotui) response _)
  "Parse response from ChatbotUI."
  (let ((content "")
        (content-end (point-max)))
    (while (re-search-forward "\\(.+\\)$" content-end t)
      (setq content (concat content "\n" (match-string 0))))
    (string-trim (replace-regexp-in-string "([a-f0-9]+ \\. [0-9]+)" "" content))))

(defun gptel--extract-content-and-base64image (data)
  "Extract content and base64image from a nested input list or vector containing multiple roles."
  (let (result)
    (dolist (item data)
      (let* ((role (plist-get item :role))
             (content-array (plist-get item :content))
             (content nil)
             (base64image nil))
        (if (vectorp content-array)
            ;; Handle vector content
            (dolist (sub-item (append content-array nil))
              (let ((type (plist-get sub-item :type)))
                (cond
                 ((string-equal type "text")
                  (setq content (plist-get sub-item :text)))
                 ((string-equal type "image_url")
                  (setq base64image (plist-get (plist-get sub-item :image_url) :url))))))
          ;; Handle direct text content
          (setq content content-array))
        ;; Build the result plist
        (let ((result-item `(:role ,role :content ,content)))
          (when base64image
            (setq result-item (append result-item `(:base64image ,base64image))))
          (setq result (append result (list result-item))))))
    (vconcat result)))

(cl-defmethod gptel--request-data ((_backend gptel-chatbotui) prompts)
  "JSON encode PROMPTS for ChatbotUI."
  (when gptel--system-message
    (setq prompts
          `(:system ,gptel--system-message
            :messages ,(gptel--extract-content-and-base64image prompts))))
  (let* ((model-plist
          `(:id ,(gptel--model-name gptel-model)
            :name ,(upcase (gptel--model-name gptel-model))
            :maxLength 96000
            :tokenLimit 128000))
         (data-plist
          `(:model ,model-plist
            :messages ,(plist-get prompts :messages)
            :key ""
            :prompt ,(plist-get prompts :system)
            :temperature ,(or (plist-get prompts :temperature) 1)
            :info ,(plist-get (elt (plist-get prompts :messages) 0) :base64image))))
    ;; (pp data-plist)
    data-plist))

(cl-defmethod gptel--parse-buffer ((_backend gptel-chatbotui) max-entries)
  "Parse current buffer backwards from point and return a list of prompts."
  (gptel--parse-buffer gptel--openai max-entries))


(cl-defmethod gptel--wrap-user-prompt ((_backend gptel-chatbotui) prompts
                                       &optional inject-media)
  "Wrap the last user prompt in PROMPTS with the context string.

If INJECT-MEDIA is non-nil wrap it with base64-encoded media
files in the context."
  (gptel--wrap-user-prompt gptel--openai prompts inject-media))

;;;###autoload
(cl-defun gptel-make-chatbotui
    (name &key (curl-args nil)
                (header nil)
                (key nil)
                (models nil)
                (stream nil)
                (host nil)
                (protocol nil)
                (endpoint nil))
  "Register an ChatbotUI backend for gptel with NAME.

Keyword arguments:

Same as gptel-ollama but defaults are suited for ChatbotUI."
  (declare (indent 1))
  (let ((backend (gptel--make-chatbotui
                  :curl-args curl-args
                  :name name
                  :host host
                  :header header
                  :key key
                  :models models
                  :protocol protocol
                  :endpoint endpoint
                  :stream stream
                  :url (concat protocol "://" host endpoint))))
    (prog1 backend
      (setf (alist-get name gptel--known-backends nil nil #'equal)
            backend))))

(provide 'gptel-chatbotui)
;;; gptel-chatbotui.el ends here
