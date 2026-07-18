import { IsOptional, IsString, MaxLength } from 'class-validator';

export class DeleteArtifactVersionDto {
  @IsOptional()
  @IsString()
  @MaxLength(500)
  reason?: string;
}
