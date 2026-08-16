import { ServiceUnavailableException } from '@nestjs/common';

import { LlmService } from '../ai/llm.service';
import { CvSummaryDto, ToolsService } from './tools.service';

type CompleteJsonParams = {
  system: string;
  user: string;
  maxTokens?: number;
  fallback: { fr: string; en: string };
};

function buildService(isConfigured: boolean) {
  const completeJson = jest.fn(async (params: CompleteJsonParams) => ({
    data: { fr: 'Résumé FR', en: 'Summary EN' },
    model: 'test-model',
    params,
  }));
  const llm = { isConfigured, completeJson } as unknown as LlmService;
  return { service: new ToolsService(llm), completeJson };
}

const dto: CvSummaryDto = {
  name: 'Awa Traoré',
  studyLevel: 'Bachelor 3',
  fieldOfStudy: 'Informatique',
  targetCountry: 'France',
  targetLevel: 'Master',
  countryOfResidence: 'Burkina Faso',
  skills: ['Python', 'Analyse de données'],
  languages: ['Français', 'Anglais (B2)'],
  experience: 'Stage KPB Education, 2024',
  objective: 'Intégrer un Master en Informatique.',
};

describe('ToolsService.generateCvSummary', () => {
  it('answers 503 when the AI provider is not configured on the server', async () => {
    // This is the ONLY legitimate reason for the app to show "AI unavailable";
    // it must stay distinguishable from a network failure client-side.
    const { service } = buildService(false);
    await expect(service.generateCvSummary(dto)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('forwards every profile fact it receives into the prompt context except the civil name', async () => {
    const { service, completeJson } = buildService(true);
    await service.generateCvSummary(dto);

    const { user } = completeJson.mock.calls[0][0];
    // IA-T2: the previous assertion `toContain('Awa Traoré')` required the
    // leak. Inverting it is the harness repair, not a behaviour change we
    // forgot to test — the name must not reach Groq.
    expect(user).not.toContain('Awa Traoré');
    expect(user).not.toContain('Nom :');
    expect(user).toContain('Bachelor 3');
    expect(user).toContain('Informatique');
    expect(user).toContain('Burkina Faso');
    expect(user).toContain('France');
    expect(user).toContain('Master');
    expect(user).toContain('Analyse de données');
    expect(user).toContain('Anglais (B2)');
    expect(user).toContain('Stage KPB Education, 2024');
    expect(user).toContain('Intégrer un Master en Informatique.');
  });

  it('omits the optional lines that were not provided', async () => {
    const { service, completeJson } = buildService(true);
    await service.generateCvSummary({
      name: 'Awa',
      studyLevel: 'Terminale',
      fieldOfStudy: 'Santé',
    });

    const { user } = completeJson.mock.calls[0][0];
    expect(user).not.toContain('Pays cible');
    expect(user).not.toContain('Objectif professionnel');
    expect(user).not.toContain('undefined');
  });

  it('forbids emoji so the generated CV PDF cannot render tofu boxes', async () => {
    // The client PDF uses the `pdf` package's built-in Helvetica: no glyph
    // above U+00FF, so an emoji is drawn as an empty rectangle. The client
    // sanitises defensively; the prompt keeps preview and PDF identical.
    const { service, completeJson } = buildService(true);
    await service.generateCvSummary(dto);

    const { system } = completeJson.mock.calls[0][0];
    expect(system).toMatch(/emoji/i);
    expect(system).toContain('texte simple');
  });

  it('returns the provider payload unchanged', async () => {
    const { service } = buildService(true);
    await expect(service.generateCvSummary(dto)).resolves.toEqual({
      fr: 'Résumé FR',
      en: 'Summary EN',
    });
  });
});

describe('ToolsService.personalizeLetters', () => {
  it('does not forward the student name into the Groq prompt', async () => {
    const { service, completeJson } = buildService(true);
    await service.personalizeLetters({
      templateKey: 'visa',
      templateBody: 'Madame, Monsieur,',
      name: 'Awa Traoré',
      fieldOfStudy: 'Informatique',
      targetCountry: 'France',
    });

    const { user } = completeJson.mock.calls[0][0];
    expect(user).not.toContain('Awa Traoré');
    expect(user).not.toContain('Nom :');
    expect(user).toContain('Informatique');
    expect(user).toContain('France');
  });
});
