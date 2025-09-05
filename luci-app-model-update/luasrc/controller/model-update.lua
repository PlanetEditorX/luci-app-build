module("luci.controller.model-update", package.seeall)

function index()
	entry({"admin", "services", "model-update"}, call("action_index"), "Smart模型更新", 90)
	entry({"admin", "services", "model-update", "log"}, call("action_log")).leaf = true
	entry({"admin", "services", "model-update", "clear"}, call("action_clear_log")).leaf = true
	entry({"admin", "services", "model-update", "status"}, call("action_status")).leaf = true
	entry({"admin", "services", "model-update", "stop"}, call("action_stop")).leaf = true
end

function action_index()
	local sys = require "luci.sys"
	local fs = require "nixio.fs"
	local uci = require "luci.model.uci".cursor()
	local http = require "luci.http"
	local dispatcher = require "luci.dispatcher"
	local template = require "luci.template"

	local raw_log = fs.readfile("/var/log/model-update.log")
	local log = "日志文件不存在。"
	if raw_log then
		local lines = {}
		for line in raw_log:gmatch("[^\r\n]+") do
			table.insert(lines, 1, line)
		end
		log = table.concat(lines, "\n")
	end

	local running = sys.call("pgrep -f model-update.sh >/dev/null") == 0
	local status = running and "运行中" or "未运行"

	local form_git_path = http.formvalue("git_path")
	local form_git_user = http.formvalue("git_user")
	local form_git_email = http.formvalue("git_email")

	local git_path = (form_git_path and form_git_path ~= "") and form_git_path or uci:get("model-update", "config", "git_path")
	local git_user = uci:get("model-update", "config", "git_user")
	local git_email = uci:get("model-update", "config", "git_email")
	local error_msg = nil

	if not git_path or git_path == "" then
		error_msg = { message = "请先设置 Git 仓库地址" }
	end

	if form_git_path then
		if not uci:get("model-update", "config", "git_path") then
			uci:section("model-update", "config", "config", { git_path = git_path })
		else
			uci:set("model-update", "config", "git_path", git_path)
		end
	end

	if form_git_user then
		uci:set("model-update", "config", "git_user", form_git_user)
		git_user = form_git_user
	end

	if form_git_email then
		uci:set("model-update", "config", "git_email", form_git_email)
		git_email = form_git_email
	end

	if form_git_path or form_git_user or form_git_email then
		uci:commit("model-update")
	end

	local form_schedule = http.formvalue("preset_schedule")
	local cron_schedule = uci:get("model-update", "config", "cron_schedule")

	if form_schedule ~= nil then
		uci:set("model-update", "config", "cron_schedule", form_schedule)
		uci:commit("model-update")
		cron_schedule = form_schedule
	end

	local pubkey = nil
	if fs.access("/root/.ssh/id_rsa.pub") then
		pubkey = fs.readfile("/root/.ssh/id_rsa.pub")
	else
		sys.call("[ -f /root/.ssh/id_rsa ] || ssh-keygen -t rsa -N '' -f /root/.ssh/id_rsa")
		if fs.access("/root/.ssh/id_rsa.pub") then
			pubkey = fs.readfile("/root/.ssh/id_rsa.pub")
		end
	end

	local btn = http.formvalue("run")
	if btn and git_path and git_path ~= "" then
		-- 清除旧任务
		sys.call("crontab -l | grep -v 'model-update' > /tmp/crontab.tmp")

		-- 如果启用了定时任务，则追加新任务
		if cron_schedule and cron_schedule ~= "" then
			local cron_line = cron_schedule .. " /etc/init.d/model-update restart\n"
			fs.writefile("/tmp/crontab.tmp", fs.readfile("/tmp/crontab.tmp") .. cron_line)
		end
		-- 应用新 crontab
		sys.call("crontab /tmp/crontab.tmp")
		fs.remove("/tmp/crontab.tmp")

		sys.call("(GIT_PATH='" .. git_path ..
				 "' GIT_AUTHOR_NAME='" .. (git_user or "") ..
				 "' GIT_AUTHOR_EMAIL='" .. (git_email or "") ..
				 "' /etc/init.d/model-update restart) &")
		http.redirect(dispatcher.build_url("admin/services/model-update"))
		return
	end

	template.render("model-update", {
		status = status,
		log = log,
		git_path = git_path,
		git_user = git_user,
		git_email = git_email,
		error_msg = error_msg,
		pubkey = pubkey,
		cron_schedule = cron_schedule
	})
end

function action_log()
	local fs = require "nixio.fs"
	local raw_log = fs.readfile("/var/log/model-update.log")
	local log = "日志文件不存在。"
	if raw_log then
		local lines = {}
		local max_lines = 200
		for line in raw_log:gmatch("[^\r\n]+") do
			table.insert(lines, 1, line)
			if #lines >= max_lines then break end
		end
		log = table.concat(lines, "\n")
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json({log = log})
end

function action_clear_log()
	local fs = require "nixio.fs"
	fs.writefile("/var/log/model-update.log", "")
	luci.http.prepare_content("application/json")
	luci.http.write_json({status = "日志已清空"})
end

function action_status()
	local sys = require "luci.sys"
	local running = sys.call("pgrep -f model-update.sh >/dev/null") == 0
	local status = running and "运行中" or "未运行"
	luci.http.prepare_content("application/json")
	luci.http.write_json({status = status})
end

function action_stop()
	local sys = require "luci.sys"
	sys.call("pkill -f model-update.sh")
	luci.http.prepare_content("application/json")
	luci.http.write_json({status = "已停止"})
end