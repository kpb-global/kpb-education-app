import { IsIn, IsString, MaxLength, MinLength } from 'class-validator';

export class EvidenceAccessQueryDto {
  @IsIn(['study_review_document'])
  purposeCode!: 'study_review_document';
}

export class EvidenceDownloadQueryDto {
  @IsString()
  @MinLength(32)
  @MaxLength(4096)
  accessToken!: string;
}

export class OutcomeEvidenceAccessQueryDto {
  @IsIn(['outcome_verification'])
  purposeCode!: 'outcome_verification';
}
