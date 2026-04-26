<#import "template.ftl" as layout>
<@layout.registrationLayout displayMessage=!messagesPerField.existsError('username','password') displayInfo=(realm.password && realm.registrationAllowed && !registrationDisabled??); section>
  <#if section = "header">
    Sign in
  <#elseif section = "form">

    <p class="chella-card__subtitle">Welcome back. Use your email or continue with Google.</p>

    <#if realm.password>
      <form id="kc-form-login" onsubmit="login.disabled = true; return true;" action="${url.loginAction}" method="post">
        <#if !usernameHidden??>
          <div class="form-group">
            <label for="username" class="control-label">
              <#if !realm.loginWithEmailAllowed>${msg("username")}<#elseif !realm.registrationEmailAsUsername>${msg("usernameOrEmail")}<#else>${msg("email")}</#if>
            </label>
            <input
              tabindex="1"
              id="username"
              class="form-control"
              name="username"
              value="${(login.username!'')}"
              type="text"
              autofocus
              autocomplete="username"
              aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>"
            />
            <#if messagesPerField.existsError('username','password')>
              <span class="kc-feedback-text" aria-live="polite">${kcSanitize(messagesPerField.getFirstError('username','password'))?no_esc}</span>
            </#if>
          </div>
        </#if>

        <div class="form-group">
          <label for="password" class="control-label">${msg("password")}</label>
          <input
            tabindex="2"
            id="password"
            class="form-control"
            name="password"
            type="password"
            autocomplete="current-password"
            aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>"
          />
        </div>

        <div id="kc-form-options">
          <#if realm.rememberMe && !usernameHidden??>
            <div class="checkbox">
              <label>
                <input tabindex="3" id="rememberMe" name="rememberMe" type="checkbox" <#if login.rememberMe??>checked</#if>>
                ${msg("rememberMe")}
              </label>
            </div>
          </#if>
          <#if realm.resetPasswordAllowed>
            <span><a tabindex="5" href="${url.loginResetCredentialsUrl}">${msg("doForgotPassword")}</a></span>
          </#if>
        </div>

        <div id="kc-form-buttons">
          <input type="hidden" id="id-hidden-input" name="credentialId" <#if auth.selectedCredential?has_content>value="${auth.selectedCredential}"</#if>/>
          <input
            tabindex="4"
            class="chella-btn chella-btn--primary"
            name="login"
            id="kc-login"
            type="submit"
            value="${msg("doLogIn")}"
          />
        </div>
      </form>
    </#if>

    <#if realm.password && social?? && social.providers?? && social.providers?has_content>
      <div class="chella-divider">or</div>
      <div class="chella-social">
        <#list social.providers as p>
          <a
            class="chella-btn chella-btn--social"
            id="social-${p.alias}"
            href="${p.loginUrl}"
            type="button"
          >
            <#if p.alias?lower_case = "google">
              <svg class="chella-social__icon" viewBox="0 0 18 18" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
                <path fill="#4285F4" d="M17.64 9.2c0-.637-.057-1.251-.164-1.84H9v3.481h4.844a4.14 4.14 0 0 1-1.796 2.716v2.258h2.908c1.702-1.567 2.684-3.875 2.684-6.615z"/>
                <path fill="#34A853" d="M9 18c2.43 0 4.467-.806 5.956-2.18l-2.908-2.259c-.806.54-1.837.86-3.048.86-2.344 0-4.328-1.584-5.036-3.711H.957v2.332A8.997 8.997 0 0 0 9 18z"/>
                <path fill="#FBBC05" d="M3.964 10.71A5.41 5.41 0 0 1 3.682 9c0-.593.102-1.17.282-1.71V4.958H.957A8.996 8.996 0 0 0 0 9c0 1.452.348 2.827.957 4.042l3.007-2.332z"/>
                <path fill="#EA4335" d="M9 3.58c1.321 0 2.508.454 3.44 1.345l2.582-2.58C13.463.891 11.426 0 9 0A8.997 8.997 0 0 0 .957 4.958L3.964 7.29C4.672 5.163 6.656 3.58 9 3.58z"/>
              </svg>
              Continue with Google
            <#else>
              ${p.displayName!p.alias}
            </#if>
          </a>
        </#list>
      </div>
    </#if>

  <#elseif section = "info">
    <#if realm.password && realm.registrationAllowed && !registrationDisabled??>
      Don't have an account?
      <a tabindex="6" href="${url.registrationUrl}">${msg("doRegister")}</a>
    </#if>
  </#if>
</@layout.registrationLayout>
