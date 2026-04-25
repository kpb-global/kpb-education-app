import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Patch,
  Post,
  Req,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';

import { StudentAuthGuard } from '../../common/guards/student-auth.guard';
import { StorageService } from '../storage/storage.service';
import { CasesService } from './cases.service';
import { CreateCaseMessageDto } from './dto/create-case-message.dto';
import { CreateCaseDto } from './dto/create-case.dto';
import { UpdateCaseDto } from './dto/update-case.dto';
import { UploadCaseDocumentDto } from './dto/upload-case-document.dto';

interface UploadedMulterFile {
  buffer: Buffer;
  originalname: string;
  mimetype: string;
  size: number;
}

@Controller('cases')
@UseGuards(StudentAuthGuard)
export class CasesController {
  constructor(
    private readonly casesService: CasesService,
    private readonly storageService: StorageService,
  ) {}

  @Get()
  findAll(@Req() req: any) {
    return this.casesService.findAll(req.studentUser.id);
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.casesService.findOne(id);
  }

  @Post()
  create(@Body() input: CreateCaseDto, @Req() req: any) {
    return this.casesService.create(input, req.studentUser.id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() input: UpdateCaseDto) {
    return this.casesService.update(id, input);
  }

  @Get(':id/messages')
  findMessages(@Param('id') id: string) {
    return this.casesService.findMessages(id);
  }

  @Post(':id/messages')
  createMessage(@Param('id') id: string, @Body() input: CreateCaseMessageDto) {
    return this.casesService.createMessage(id, input);
  }

  @Post(':id/documents')
  registerDocument(
    @Param('id') id: string,
    @Body() input: UploadCaseDocumentDto,
  ) {
    return this.casesService.uploadDocument(id, input);
  }

  @Post(':id/documents/upload')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 10 * 1024 * 1024 } }))
  async uploadDocument(
    @Param('id') id: string,
    @Body() input: UploadCaseDocumentDto,
    @UploadedFile() file: UploadedMulterFile | undefined,
  ) {
    if (!file) {
      throw new BadRequestException('File is required under field "file".');
    }
    if (!this.storageService.isAllowedMime(file.mimetype)) {
      throw new BadRequestException(
        `Unsupported file type: ${file.mimetype}. Allowed: PDF, JPEG, PNG, HEIC, WebP.`,
      );
    }
    const stored = await this.storageService.save(
      file.buffer,
      file.originalname,
      file.mimetype,
    );
    return this.casesService.uploadDocument(id, {
      title: input.title || file.originalname,
      fileUrl: stored.url,
    });
  }
}
