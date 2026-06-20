import { Body, Controller, Post, UseGuards } from '@nestjs/common';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import {
  DocumentKind,
  DocumentReviewService,
} from './document-review.service';

@Controller('document-review')
@UseGuards(StudentAuthGuard)
export class DocumentReviewController {
  constructor(private readonly service: DocumentReviewService) {}

  /// Returns structured, on-rubric feedback for a pasted motivation letter / CV.
  @Post()
  review(@Body() body: { kind?: string; text?: string }) {
    const kind: DocumentKind = body?.kind === 'cv' ? 'cv' : 'motivation';
    return this.service.review(kind, body?.text ?? '');
  }
}
