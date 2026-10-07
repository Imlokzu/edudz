/// The fork owns its server selection; upstream remote configuration is disabled.
const String ep2ServerUrl = String.fromEnvironment(
  'EDUDZ_SERVER_URL',
  defaultValue: 'https://ep2.waveio.me',
);
