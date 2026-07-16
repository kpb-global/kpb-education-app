import {
  BadRequestException,
  Body,
  Controller,
  Get,
  NotFoundException,
  Param,
  Patch,
  Post,
  Res,
  Req,
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

  @Get(':id/documents/:documentId/file')
  async downloadDocument(
    @Param('id') id: string,
    @Param('documentId') documentId: string,
    @Req() req: any,
    @Res() response: Response,
  ): Promise<void> {
    const document = await this.casesService.getOwnedDocument(
      id,
      documentId,
      req.studentUser.id,
    );
    const key = this.storageService.keyFromUrl(document.fileUrl);
    if (!key) {
      throw new NotFoundException('Document not found.');
    }
    const object = await this.storageService.getObject(key);
    if (!object) {
      throw new NotFoundException('Document not found.');
    }

    response.setHeader('Content-Type', object.mimeType);
    response.setHeader('Content-Disposition', 'attachment');
    response.setHeader('Cache-Control', 'private, no-store');
    response.setHeader('X-Content-Type-Options', 'nosniff');
    if (object.sizeBytes !== undefined) {
      response.setHeader('Content-Length', object.sizeBytes.toString());
    }
    object.stream.on('error', () => {
      if (!response.headersSent) {
        response.status(503).end();
      } else {
        response.destroy();
      }
    });
    object.stream.pipe(response);
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
  registerDocument() {
    // This legacy JSON endpoint used to accept a client-provided file URL.
    // A document can now be marked provided only by the validated multipart
    // route below, which is the sole code path allowed to write a file URL.
    throw new BadRequestException(
      'Use the multipart /documents/upload endpoint to provide a document.',
    );
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
    const stored = await this.storageService.save(
      file.buffer,
      file.originalname,
      file.mimetype,
    );
    return this.casesService.uploadDocument(
      id,
      {
        title: input.title || file.originalname,
      },
      req.studentUser.id,
      stored.url,
    );
  }
}
