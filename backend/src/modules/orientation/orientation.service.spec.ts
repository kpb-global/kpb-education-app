import { Test, TestingModule } from '@nestjs/testing';
import { OrientationService } from './orientation.service';
import { NotFoundException } from '@nestjs/common';

describe('OrientationService', () => {
  let service: OrientationService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [OrientationService],
    }).compile();

    service = module.get<OrientationService>(OrientationService);
  });

  describe('Orientation Matching Engine', () => {
    it('should generate accurate field recommendations based on keyword answers', () => {
      const session = service.createSession({
        answers: {
          q1: ['I love technology'],
          q2: ['data analysis and systems'],
        },
      });

      expect(session).toBeDefined();
      expect(session.id).toBeDefined();
      expect(session.recommendations.length).toBeGreaterThan(0);
      
      // Points allocation based on OrientationService logic:
      // 'technology' -> CS(+4), Eng(+3)
      // 'analysis' -> CS(+4), Eng(+3)
      // Total CS = 8 * 10 = 80
      
      const csRecommendation = session.recommendations.find(r => r.fieldId === 'computer_science');
      expect(csRecommendation).toBeDefined();
      expect(csRecommendation!.score).toBeGreaterThanOrEqual(80);
      
      // Ensure sorting order
      expect(session.recommendations[0].fieldId).toBe('computer_science');
    });

    it('should fall back to minimum 60 score if very few keywords hit', () => {
        const session = service.createSession({
          answers: {
            q1: ['business'], // Only 1 hit: +4 points. 4 * 10 = 40. Min is 60.
          },
        });
  
        const bizRec = session.recommendations.find(r => r.fieldId === 'business');
        expect(bizRec).toBeDefined();
        expect(bizRec!.score).toBe(60); // Due to Math.max(score * 10, 60)
    });

    it('should throw NotFoundException for unknown session ID', () => {
        expect(() => service.getResults('invalid-id')).toThrow(NotFoundException);
    });
  });
});
