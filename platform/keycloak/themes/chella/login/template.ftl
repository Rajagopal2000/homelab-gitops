<#macro registrationLayout bodyClass="" displayInfo=false displayMessage=true displayRequiredFields=false>
<!DOCTYPE html>
<html lang="en" class="${properties.kcHtmlClass!}">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
  <meta name="robots" content="noindex, nofollow">
  <title>${msg("loginTitle",(realm.displayName!''))}</title>
  <link rel="icon" href="${url.resourcesPath}/img/logo.svg">
  <#if properties.stylesCommon?has_content>
    <#list properties.stylesCommon?split(' ') as style>
      <link href="${url.resourcesCommonPath}/${style}" rel="stylesheet">
    </#list>
  </#if>
  <#if properties.styles?has_content>
    <#list properties.styles?split(' ') as style>
      <link href="${url.resourcesPath}/${style}" rel="stylesheet">
    </#list>
  </#if>
  <#if scripts??>
    <#list scripts as script>
      <script src="${script}" type="text/javascript"></script>
    </#list>
  </#if>
</head>
<body class="${bodyClass}">
  <div class="chella-shell">
    <header class="chella-header">
      <div class="chella-header__inner">
        <#-- Falls back to Keycloak account console if the originating app
             didn't supply a baseUrl (e.g. user navigated to /auth directly). -->
        <a class="chella-brand" href="${(client.baseUrl)!url.loginAction}">Chella</a>
      </div>
    </header>

    <main class="chella-main">
      <div class="chella-card">
        <h1 class="chella-card__title">
          <#nested "header">
        </h1>

        <#if displayMessage && message?has_content && (message.type != 'warning' || !isAppInitiatedAction??)>
          <div class="alert alert-${message.type}">
            <span class="kc-feedback-text">${kcSanitize(message.summary)?no_esc}</span>
          </div>
        </#if>

        <#nested "form">

        <#if displayInfo>
          <div class="chella-card__footer">
            <#nested "info">
          </div>
        </#if>
      </div>
    </main>

    <footer class="chella-foot">
      &copy; Chella Caterers
    </footer>
  </div>
</body>
</html>
</#macro>
