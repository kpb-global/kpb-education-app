import { Injectable, NotFoundException } from '@nestjs/common';

type Answers = Record<string, string[]>;

@Injectable()
export class OrientationService {
  private readonly sessions: Array<Record<string, unknown>> = [];

  createSession(body: Record<string, unknown>) {
    const answers = (body.answers as Answers | undefined) ?? {};
    const scores = new Map<string, number>();

    for (const selected of Object.values(answers)) {
      for (const answer of selected) {
        if (answer.includes('technology') || answer.includes('analysis')) {
          scores.set('computer_science', (scores.get('computer_science') ?? 0) + 4);
          scores.set('engineering', (scores.get('engineering') ?? 0) + 3);
        }
        if (answer.includes('business') || answer.includes('communication')) {
          scores.set('business', (scores.get('business') ?? 0) + 4);
        }
        if (answer.includes('care') || answer.includes('impact')) {
          scores.set('medicine', (scores.get('medicine') ?? 0) + 4);
        }
      }
    }

    const recommendations = Array.from(scores.entries())
      .sort((left, right) => right[1] - left[1])
      .slice(0, 3)
      .map(([fieldId, score]) => ({
        fieldId,
        score: Math.max(score * 10, 60),
        explanation: {
          fr: 'Ce choix ressort à partir de vos centres d’intérêt et de votre profil académique.',
          en: 'This option stands out based on your interests and academic profile.',
        },
      }));

    const session = {
      id: `orientation-${Date.now()}`,
      completedAt: new Date().toISOString(),
      answers,
      recommendations,
      nextActions: {
        fr: 'Explorez les programmes liés et demandez un accompagnement KPB.',
        en: 'Explore related programs and request KPB support.',
      },
    };

    this.sessions.unshift(session);
    return session;
  }

  getResults(id: string) {
    const session = this.sessions.find((item) => item.id === id);
    if (!session) {
      throw new NotFoundException(`Orientation session ${id} not found.`);
    }
    return session;
  }
}
