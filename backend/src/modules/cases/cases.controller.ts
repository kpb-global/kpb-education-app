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
  findOne(@Param('id') id: string, @Req() req: any) {
    return this.casesService.findOne(id, req.studentUser.id);
  }

  @Post()
  create(@Body() input: CreateCaseDto, @Req() req: any) {
    return this.casesService.create(input, req.studentUser.id);
  }

  @Patch(':id')
  update(
    @Param('id') id: string,
    @Body() input: UpdateCaseDto,
    @Req() req: any,
  ) {
    return this.casesService.update(id, input, req.studentUser.id);
  }

  @Get(':id/messages')
  findMessages(@Param('id') id: string, @Req() req: any) {
    return this.casesService.findMessages(id, req.studentUser.id);
  }

  @Post(':id/messages')
  createMessage(
    @Param('id') id: string,
    @Body() input: CreateCaseMessageDto,
    @Req() req: any,
  ) {
    return this.casesService.createMessage(id, input, req.studentUser.id);
  }

  @Post(':id/documents')
  registerDocument(
    @Param('id') id: string,
    @Body() input: UploadCaseDocumentDto,
    @Req() req: any,
  ) {
    return this.casesService.uploadDocument(id, input, req.studentUser.id);
  }

  @Post(':id/documents/upload')
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: 10 * 1024 * 1024 } }))
  async uploadDocument(
    @Param('id') id: string,
    @Body() input: UploadCaseDocumentDto,
    @UploadedFile() file: UploadedMulterFile | undefined,
    @Req() req: any,
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
    return this.casesService.uploadDocument(
      id,
      {
        title: input.title || file.originalname,
        fileUrl: stored.url,
      },
      req.studentUser.id,
    );
  }
}
