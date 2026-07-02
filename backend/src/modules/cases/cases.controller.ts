import {
  BadRequestException,
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  Req,
  Res,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import type { Response } from 'express';

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
    // Force senderRole — students must never choose their own role.
    return this.casesService.createMessage(
      id,
      { body: input.body, senderRole: 'student', senderName: req.studentUser.email },
      req.studentUser.id,
    );
  }

  @Post(':id/documents')
  registerDocument(
    @Param('id') id: string,
    @Body() input: UploadCaseDocumentDto,
    @Req() req: any,
  ) {
    return this.casesService.uploadDocument(id, input, req.studentUser.id);
  }

  // Authenticated document download — replaces the old public /uploads static
  // route. Ownership is verified (a doc on another user's case → 404), then the
  // file is streamed from local disk or proxied from S3.
  @Get(':id/documents/:docId/file')
  async downloadDocument(
    @Param('id') id: string,
    @Param('docId') docId: string,
    @Req() req: any,
    @Res() res: Response,
  ) {
    const doc = await this.casesService.getOwnedDocument(
      id,
      docId,
      req.studentUser.id,
    );
    const key = this.storageService.keyFromUrl(doc.fileUrl);
    const object = key ? await this.storageService.getObject(key) : null;
    if (!object) {
      throw new NotFoundException('Document file not found.');
    }
    res.setHeader('Content-Type', object.contentType);
    if (object.contentLength != null) {
      res.setHeader('Content-Length', String(object.contentLength));
    }
    res.setHeader('Content-Disposition', 'inline');
    res.setHeader('Cache-Control', 'private, no-store');
    object.stream.pipe(res);
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
