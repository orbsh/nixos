;; Nyxt 配置
;; 文档: https://nyxt.atlas.engineer/manual

;; 启动页面
(define-configuration browser
  (startup-function (lambda (browser)
                      (nyxt/open-url browser "https://google.com"))))

;; 代理（取消注释以启用）
;; (define-configuration browser
;;   (proxy-mode-p t)
;;   (proxy (quri:uri "http://localhost:7890")))

;; 字体
(define-configuration browser
  (user-font-size 14))
