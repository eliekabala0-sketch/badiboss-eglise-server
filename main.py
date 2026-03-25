from server_multichurch import LoginIn, app, login


@app.post("/church/login")
def church_login_alias(body: LoginIn):
    return login(body)
