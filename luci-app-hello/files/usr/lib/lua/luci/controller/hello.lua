module("luci.controller.hello", package.seeall)
function index()
    entry({"admin", "system", "hello"}, template("hello/index"), "Hello World", 100)
end