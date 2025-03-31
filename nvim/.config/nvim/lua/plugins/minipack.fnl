(local M {})

(local config {:pack_dir (.. (vim.fn.stdpath :data) :/site/pack/plugins/start)
               :plugins []
               :verbose false})

(fn log [msg ?level]
  (when (or config.verbose (= ?level :error))
    (let [level (or ?level :info)]
      (print (.. "[minipack] " (if (= level :error) "ERROR: " "") msg)))))

(fn execute [cmd]
  (let [handle (io.popen (.. cmd " 2>&1"))]
    (if (not handle)
        (do
          (log (.. "Failed to execute: " cmd) :error)
          (values nil 1))
        (let [result (handle:read :*a)
              (success _ code) (handle:close)]
          (if success
              (values result 0)
              (do
                (log (.. "Command failed with code" (or code :unknown) ": " cmd)
                     :error)
                (log result :error)
                (values result code)))))))

(fn get_plugin_name [url]
  (or (string.match url "/([^/]+).git$") (string.match url "/([^/]+)$")
      (string.match url "([^/]+)$")))

(set M add (fn [url ?ref]
             (let [ref (or ?ref :HEAD)
                   name (get_plugin_name url)]
               (if name
                   (do
                     (table.insert config.plugins {: name : url : ref})
                     M)
                   (log (.. "Could not determine plugin name from URL: " url)
                        :error)))))

M
