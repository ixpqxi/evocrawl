const fs = require('fs');

const sourcePath = process.env.EVOCRAWL_LOGIN_CONFIG_SOURCE || '/opt/evocrawl/utils-evo/login_information.defaults.json';
const targetPath = process.env.EVOCRAWL_LOGIN_CONFIG_TARGET || '/opt/evocrawl/utils-evo/login_information.json';
const appName = process.env.APPNAME || 'kanboard';

const config = JSON.parse(fs.readFileSync(sourcePath, 'utf8'));

const setIfPresent = (envName, key) => {
  if (process.env[envName] !== undefined && process.env[envName] !== '') {
    config[key] = process.env[envName];
  }
};

const getEnv = (envName) => {
  if (process.env[envName] === undefined || process.env[envName] === '') {
    return undefined;
  }
  return process.env[envName];
};

const setNthIfPresent = (step, envName) => {
  const value = getEnv(envName);
  if (value !== undefined) {
    const nth = Number(value);
    if (Number.isNaN(nth)) {
      throw new Error(`${envName} must be a number`);
    }
    step.nth = nth;
  }
};

const buildSelectorStep = (action, selectorEnv, value) => {
  const selector = getEnv(selectorEnv);
  if (selector === undefined) {
    return null;
  }

  const step = { action, selector };
  if (value !== undefined) {
    step.value = value;
  }
  return step;
};

const renderLoginProfileFromEnv = () => {
  const usernameStep = buildSelectorStep('type', 'LOGIN_USERNAME_SELECTOR', '$username');
  const passwordStep = buildSelectorStep('type', 'LOGIN_PASSWORD_SELECTOR', '$password');
  const submitStep = buildSelectorStep('click', 'LOGIN_SUBMIT_SELECTOR');

  if (!usernameStep && !passwordStep && !submitStep) {
    return;
  }

  if (!usernameStep || !passwordStep || !submitStep) {
    throw new Error('LOGIN_USERNAME_SELECTOR, LOGIN_PASSWORD_SELECTOR, and LOGIN_SUBMIT_SELECTOR must be set together');
  }

  setNthIfPresent(usernameStep, 'LOGIN_USERNAME_NTH');
  setNthIfPresent(passwordStep, 'LOGIN_PASSWORD_NTH');
  setNthIfPresent(submitStep, 'LOGIN_SUBMIT_NTH');

  const steps = [
    { action: 'navigate', url: '$url' },
    usernameStep,
    passwordStep,
    submitStep
  ];

  const postWaitMs = getEnv('LOGIN_POST_WAIT_MS');
  if (postWaitMs !== undefined) {
    const ms = Number(postWaitMs);
    if (Number.isNaN(ms)) {
      throw new Error('LOGIN_POST_WAIT_MS must be a number');
    }
    if (ms > 0) {
      steps.push({ action: 'wait', ms });
    }
  }

  config.login_profiles = config.login_profiles || {};
  config.login_profiles[appName] = { steps };
};

if (process.env.TARGET_URL !== undefined && process.env.TARGET_URL !== '') {
  config[appName] = process.env.TARGET_URL;
}

setIfPresent('LOGIN_CRAWLER_USER', 'crawler');
setIfPresent('LOGIN_PASSWORD', 'password');
setIfPresent('LOGIN_TOKEN_USER', 'token_user');
setIfPresent('LOGIN_FILTER_USER', 'filter');
setIfPresent('LOGIN_DETECTOR_USER', 'detector');
setIfPresent('LOGIN_USER_B', 'userB');
setIfPresent('LOGIN_TOKEN_NAME', 'token');
setIfPresent('LOGIN_FOLDER', 'folder');

renderLoginProfileFromEnv();

fs.writeFileSync(targetPath, `${JSON.stringify(config, null, 4)}\n`);
console.log(`Rendered ${targetPath} for ${appName}`);
